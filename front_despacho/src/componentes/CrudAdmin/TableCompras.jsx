import { useState, useEffect } from "react";
import { Modal } from "./Modal";
import { FormDespacho } from "./FormDespacho";
import axios from "axios";

// URL base del backend - usa variable de entorno o ruta relativa via proxy nginx
const API_BASE = import.meta.env.VITE_API_BASE || "/api";

export const TableCompras = () => {
  const [ventas, setVentas] = useState([]);

  const cargarCompras = async () => {
    await axios
      .get(`${API_BASE}/v1/ventas`, {
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
        },
      })
      .then((response) => {
        console.log(response.data);
        setVentas(response.data);
      })
      .catch((error) => {
        console.error("Error al cargar ventas:", error);
      });
  };

  useEffect(() => {
    cargarCompras();
  }, []);

  const [openModal, setOpenModal] = useState(false);
  const [ventaSeleccionada, setVentaSeleccionada] = useState(null);

  const handleAbrirModal = (venta) => {
    setVentaSeleccionada(venta);
    setOpenModal(true);
  };

  return (
    <>
      <section className="grid text-center grid-cols-12 mb-8">
        <div className="col-span-12 flex justify-center">
          <div className="col-span-10 p-2 bg-white border border-gray-200 rounded-lg shadow dark:bg-white h-full overflow-hidden">
            <table className="table-fixed">
              <thead>
                <tr className="py-10">
                  <th className="pr-10">Orden de compra</th>
                  <th className="pr-10">Dirección</th>
                  <th className="pr-10">Fecha de compra</th>
                  <th className="pr-10">Valor total</th>
                  <th className="pr-10">Acciones</th>
                </tr>
              </thead>
              <tbody>
                {ventas
                  .filter((venta) => !venta.despachoGenerado)
                  .map((venta) => (
                    <tr key={venta.idVenta}>
                      <td className="pr-10 py-10 items-center">
                        {venta.idVenta}
                      </td>
                      <td className="pr-10 py-10 items-center">
                        {venta.direccionCompra}
                      </td>
                      <td className="pr-10 py-10 items-center">
                        {venta.fechaCompra}
                      </td>
                      <td className="pr-10 py-10 items-center">
                        ${venta.valorCompra}
                      </td>
                      <td>
                        <button
                          onClick={() => handleAbrirModal(venta)}
                          className="py-1 bg-orange-200 px-8 rounded-xl shadow-md hover:bg-orange-300/70 transition-all duration-300"
                        >
                          Generar Despacho
                        </button>
                      </td>
                    </tr>
                  ))}
              </tbody>
            </table>
          </div>
        </div>
      </section>
      <Modal
        onClose={() => {
          setOpenModal(false);
        }}
        open={openModal}
      >
        {ventaSeleccionada && (
          <FormDespacho
            venta={ventaSeleccionada}
            onClose={() => {
              setOpenModal(false);
              cargarCompras();
            }}
          />
        )}
      </Modal>
    </>
  );
};
